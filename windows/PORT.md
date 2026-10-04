# Windows migration roadmap

2026-10-03. Target: Windows 11 x86_64. Current stage: native Win32 prayer-rope presentation and keyboard milestone
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
milestone below. Notification delivery, onboarding and complete
visual/accessibility parity remain outstanding; the feature gates below are still the full inventory.

## Settings and record milestone

Names/clear, clock style, Progress figure, church/unnamed fallback, independent
calendar reckoning, fasting/feast observance and the old-style-date preference
now persist through core settings. Reckoning changes save the scoring cutoff
without rewriting occurrence history. Calendar settings now select the core service and Home annotations. Styled prayer/reading text is covered by the milestone below;
calendar glossary links and full visual/input acceptance remain open.

Native backup dialogs export the portable JSON record and merge restores.
SQLite imports now run in one locked transaction, also preserving the existing
scoped-edit transaction guarantee. A failed import rolls back its earlier writes.
Local daily backups retain ten dated copies and leave other files alone. A Win32
timer plus foreground/resume events drive day rollover through core, retaining
past selection and deferring date changes while an editor is open. Synthetic
review files live in a separate temporary directory and are removed on exit.
Notification/quiet-hours, sound, startup/taskbar and onboarding controls
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

Remaining parity work includes keyboard/mouse and UI Automation accessibility, responsive layouts beyond
Home, measured card expansion and automatic reveal, subject-focused artwork
motion/reduced motion, rope sounds/animation, and remaining reading ornaments. Inline reading and
appointed-kathisma interaction are covered by the milestone below. Platform
services and packaging gates below remain mandatory.

## Windows tray milestone and platform exception

The Windows tray is a native four-item menu, not the macOS mini-app:

1. Open Chotki restores and foregrounds the main window on Home.
2. Silence notifications / Enable notifications toggles and persists
   `reminders.notificationsEnabled`; its label and the Settings checkbox agree.
3. Settings restores and foregrounds the Settings tab.
4. Quit removes the tray icon and exits the application.

Mouse clicks and keyboard activation open the same menu. The rope mark uses
canonical core geometry. Closing the main window keeps the app in the tray;
if tray registration fails, closing exits so no unreachable process remains.
Taskbar recreation registers the icon again. Native synthetic checks cover
menu structure, persisted toggles, typed Settings preservation, window hiding,
Home routing, minimized Settings restoration, taskbar recovery and Quit.
Notification delivery remains a separate outstanding service milestone.

## Styled reader and glossary milestone

Prayers now preserve titles, rubrics, paragraphs and source credits in a native
Unicode rich-text reader. Glossary scanning uses the canonical scoped index and
links each term only once across a full sequence. Akathist paragraphs use the
same rules. Saint lives preserve bold/italic spans, section headings, rows and
source/license credits; scripture references have separate quiet headings.
Source links open the browser, while glossary links stay inside the app.

The glossary provides categorized browsing with summaries, search, pronunciation,
related entries and All terms. A reading detour overlays the current content,
retaining the native reader and rope state. Back restores focus and position.
Resize keeps the detour open, and day rollover waits while it is open. Mouse
links and keyboard Enter follow the same routes. Native checks exercise styling,
UTF-16 offsets, source links, term deduplication, search and related navigation,
return position, resize, 40 reader redraws, 20 glossary round trips, a burst of
100 calendar refreshes, and programmatic-versus-deliberate completion. Calendar refresh updates the heading
without disposing an active native reader, preserving its layout and position.

After the native lifecycle changes, five consecutive full UI suites completed
under Prism with exit code 0. The final build confirmed AMD64 architecture and
bundled runtime dependencies; 13 synthetic captures were retrieved through
SSH, and the prayer/glossary views were visually inspected. Physical input and
real x86_64 hardware acceptance
remain separate gates.

The UI holds an OLE apartment for native text controls and destroys only owned
parent controls during redraws. Two persistent Unicode RichEdit20W controls are
parked outside the page while inactive and reused for reading and glossary
content. Their keyboard/link/scroll behavior uses native notifications. Native
commands reach Swift on the next loop turn, after the originating control's
procedure has returned, so page redraws cannot destroy a button mid-click.
The Swift callback owner is retained for the full native-loop lifetime. Legacy
plain editor/backup controls remain separate. Calendar-term links on every
surface, reading ornaments and complete accessibility/DPI acceptance remain open.

## Inline reading and appointed Psalter milestone

Each reading heading now expands its text in place, and several sections can
remain open together. A Home rule focuses its own section; entering Reading
from the sidebar begins with sections closed. Native rich-text links support
mouse and keyboard disclosure while reusing the existing reader. Disclosure
retains the visible line; glossary detours continue to retain the native control.
Fasting notes, patristic text and calendar footers follow the Mac content order.

The Psalter uses the canonical Kathisma appointments grouped by service, using
the cached calendar's Pascha distance and the Mac's ordinary-season fallback.
All twenty kathismata are available through the browse control. Manual and
appointed selections are independent, and each expanded portion carries its
complete psalms, superscriptions and verses in Septuagint numbering. Bright
Week explains the absence of appointments, while manual reading stays available.
Opening a new Psalter route starts with its rows closed and returning to Prayers
preserves the rope selection and count.

Native completion ranges belong only to expanded, populated sections. Deliberate
scrolling that reaches or passes a section's end completes that section's rule;
closed headings, missing text and programmatic scrolling do not. A kathisma's
range ends after its last verse. Redraws replace completion tokens so stale
notifications cannot mark a different page or date. Stood-down and dispensed
entries retain their existing status. Shared calendar, text and completion
policy remain canonical core decisions; only presentation belongs to Windows.

The final explicit x86_64 build, bootstrap and complete desktop UI suite passed
with exit code 0 under Prism, with PE machine 0x8664 and verified bundled DLLs.
Native checks distinguish the Gospel's end from an unread Epistle, reject stale
completion tokens, activate disclosures through pointer notifications and Enter,
and verify the first and last verses of all twenty manual kathismata. They also
cover cached Bright Week and stood-down preservation. Seventeen synthetic window
captures were retrieved through SSH; inline reading, full/narrow Psalter and
Bright Week were visually inspected. Installed-font glyph checks select Segoe UI
Symbol for the chevrons that Charter and Segoe UI do not provide.

Next: remaining Library/Progress and Settings layouts, then notifications, audio,
startup and packaging services.
Full visual parity, reading ornaments, physical input, UI Automation and real
x86_64 hardware acceptance remain required. These are development milestones,
not a Windows release candidate.

## Prayer rope presentation and keyboard milestone

The Prayers page now presents the Mac's large gold count, one smooth circle per
knot, a full-width Count button, completion caption and selected 33/50/100 target.
The footer provides Start again and a manual Show/Hide rope override. A native
chooser groups Rules, On the rope and Read under disabled headings and includes
The rope alone. Canonical PrayerScreen and scoped PrayerBook own selection,
count, target, visibility and completion decisions. Count and reset repaint only
the counter, retaining the live reader and reading position. Individual prayer
words are centred at 20 pixels; full sequences retain their paragraph layout.
The reused reader explicitly restores left alignment for other reading surfaces.

Space counts from the main prayer surface, Count button or prayer reader. Held-key
repeat is consumed without counting, including after the interval has elapsed;
the core's one-second guard also rejects rapid separate clicks or presses.
Modified Space, chooser/footer focus, a hidden rope, glossary overlays, editors,
Psalter and other tabs do not take the counting shortcut. Both the real message
loop and the synthetic pump share this routing. Native menu selections are
posted after the menu returns and checked against the originating control's
serial so a nested day rollover cannot act on disposed state.

The explicit x86_64 build, bootstrap and complete UI suite passed under Prism
with exit code 0. Checks cover native menu grouping, repeat/interval/modifier
isolation, count/display/target synchronization, completion without exceeding
the target, manual visibility, rope-only mode, glossary return, preservation of
stood-down entries, and rejection of rope completion for an unread morning rule.
Twenty-two synthetic captures were retrieved through SSH; the full, completed,
read-through, rope-only and compact 100-knot views were inspected. The compact
layout retains separate text and footer areas at the minimum 620×540 size.

Tick/chime playback and sound settings, rope transitions/reduced motion, physical
mouse/keyboard acceptance and UI Automation remain open. The Windows tray still
has only its four specified commands. No Windows release candidate is created.

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
   and Settings. Preserve desktop sidebar and the simple Windows tray menu, detached Progress
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
  pulse must work in the main window. The Windows tray has no rope controls. A correct screenshot
  is only layout evidence; drive physical mouse/keyboard interaction separately.

## Verification limits and risks

The initial window and seven navigation surfaces compile with ChotkiCore. They
cover a subset of actions; all 477 core tests now pass on Windows x86_64, while
the broader parity inventory remains outstanding. Synthetic control checks exercise native
button messages, not physical keyboard/mouse input. An ARM64 VM running an
x86_64 app exercises Windows emulation; retain a later real x86_64 Windows 11
acceptance check. The native Win32 loop now receives asynchronous cache updates through posted
messages; broader physical input and accessibility acceptance remain open.
Never open or copy live data.

## Primary toolkit references

- [Swift Windows prerequisites](https://www.swift.org/install/windows/manual/)
- [SwiftWin32](https://github.com/compnerd/swift-win32): Win32 wrappers, SwiftPM
  support, and documented extra manifest/resource deployment steps.
- [Swift/WinRT](https://github.com/thebrowsercompany/swift-winrt): WinRT
  projection to evaluate for a WinUI 3 approach.

These are candidates to test, not a claim that Chotki's complete UI already
works with either toolkit. Do not substitute their default build examples for
this project's mandatory x86_64 command.

## Library, Progress and Settings parity milestone

The native Library now presents tradition-scoped category rows, summaries,
observance notes, glossary detours and saved custom entries. A new template opens
the editor before activation; a paused copy resumes with its existing identity
and history. The shared custom-rule caution supports Cancel and a persistent
Don't Show Again choice.

Progress leads with the shared thirty-day prose through yesterday, an optional
figure and per-rule kept/scoreable details. Its separate, reusable window reports
ninety days. The unchanged Mac Progress artwork, quotation and caption are
bundled and stationary. Native Rich Edit size requests fit prose into the outer
page scroll instead of adding a nested reader scrollbar.

Settings follows the Mac section order in one scrolling form. Names persist
without destroying focus; church, reckoning, observances, clock, notifications,
default warning lead, rope sounds, record backups, taskbar presence and login
preferences are available. The login adapter uses the current-user Run key;
synthetic reviews exercise a private in-memory registration route and do not
change the user's login configuration.

The x86_64 build and complete synthetic suite passed for Library/Progress/
Settings, with PE and bundled runtime verification. Progress, its report window,
Library rows, artwork and Settings captures have been visually inspected. The
expanded combined desktop suite now has a bounded 120-second deadline; its
verified-PID cleanup still removes only its own synthetic child and task.

The first-run welcome, Windows PCM sound adapter, motion, responsive editor,
measured cards, prayer ornaments and physical input have passed VM verification.
Installed startup, packaging and final acceptance remain gates.
No Windows release candidate has been created.

## First run, sound and native notification milestone

The welcome uses canonical Welcome paragraphs and church choices, preserves
typed Unicode text over resizing, persists first-run metadata and activates no
implicit rules. Five prepared Windows PCM voices play the core-generated tick
and bell; automated reviews verify device preparation and audio policy quietly.
Rapid/rejected presses do not tick, and completion honors the chime setting.

Reminders now use ChotkiCore Scheduler, ReminderTicker and DueAttention. The
resident timer ticks every thirty seconds and refreshes on practice changes.
Native Windows toasts carry Complete and Snooze actions through a COM activator;
settled and silenced occurrences withdraw their banners. Early warnings do not
pulse navigation; due attention uses the shared duration and respects Windows
client-area animation preferences.

The complete synthetic UI suite passed with native XML/Unicode delivery, no
repeat banners, COM action routing, cancellation and master silence. A separate
interactive VM smoke test also passed real Windows notification-history receipt
and native WinRT/COM actions with exit 0. Its temporary shortcut, COM registration,
PID and scheduled task are cleaned separately from the real app identity. See
NOTIFICATIONS.md for the licensed compatibility helper and upstream references.

Remaining gates are optimized-build acceptance, installed startup behavior,
packaging and final user acceptance. No release
candidate has been declared or published.


## Motion, complete prayers and physical input milestone

The opening and daily artwork use canonical Mac geometry, focal positions and
motion timings, honor reduced motion, and settle without restarting on page
changes. The opening is once per process; a hidden login defers it until the
first foreground visit. Expanded cards measure their complete content and reveal
themselves horizontally. Rule editors remain usable at the minimum window size.
The thirty-day spiritual-father prompt follows the core policy and saves or defers
the answer. Attached-rule prayer views contain every received prayer, canonical
source references and the Mac ornament; consulting them never marks the rule kept.

Physical mouse and keyboard verification passed Unicode names, Ctrl+A, notification
switches, their native accessibility roles and TogglePattern, the rope's Space
interval guard, count/reset, native grouped-menu selection and Library editor
navigation. The harness uses physical DPI coordinates and compiled UI Automation
provider initialization rather than relying on PowerShell's dynamic call stack.

Home context menus now expose destination, expand/collapse, kept/late/stand-down,
glossary, edit and pause/resume actions. Fasting cards expose their glossary link.
The complete debug desktop suite passed and its prayer ornament/reader composition,
opening and minimum-size forms have been visually inspected.

## Packaging framework and acceptance gates

`prepare-branding.py` renders the canonical shared mark into a multi-size Windows
icon and takes the version from `macos/version.env`. The SDK resource compiler
embeds icon, version and an AMD64, per-monitor-DPI manifest. Optimized builds use
the GUI subsystem and retain the mandatory target and compiler environment.
`package-vm.ps1` assembles only the executable, x64 DLLs, resource bundles, icon,
notices and installation/launch scripts. A SHA-256 manifest covers the payload.
The installer supports current-user installation with Desktop and Start menu
shortcuts, validates inputs, guards existing installations and keeps practice
records outside the program directory. Launchers isolate the runtime search path.

`--lifecycle-smoke` exercises the real window, instance and opening adapters with
in-memory practice and a private window/mutex/Run-key namespace. It never opens a
live record or changes the real login preference. The lifecycle wrapper runs it
on the logged-in desktop with bounded cleanup. These package and lifecycle gates
must pass before an RC is declared; assembly alone does not establish readiness.

## Windows x86_64 release candidate acceptance

The first candidate is `windows-v1.0-beta.30-rc1`, using the canonical build-30
version. The optimized GUI build, complete synthetic desktop suite, visual
review, physical mouse/keyboard/accessibility (including independent Home-card
completion), real Windows notification delivery and native COM actions passed.
The assembled payload and installed copy passed SQLite/settings/JSON/Psalter
bootstrap, file hashes, AMD64 executable/DLL checks and private lifecycle review.
The lifecycle review verified hidden login, second-instance Home restoration,
the actual timed opening, native login registration/removal, Settings,
close-to-tray and Quit with exit 0. Its private registry and task were removed.

Installation on the VM is `%LOCALAPPDATA%\Programs\Chotki`, with a `Chotki`
Desktop icon and Start menu shortcut. Installation and acceptance did not open
live practice records. The release ZIP carries the integrity manifest and
notices. The published candidate is ready for the user's form/function testing;
real x86_64 hardware and native ARM64 are not claimed as verified by this VM.
