# Completing the Linux port

Written 2026-10-10, at the handoff from Codex. `linux/PORT.md` remains the record of Phases 0 and 1 and the original gates. This file is the plan for the work that is still open. Do not start a slice until the slice before it has met its gate.

## Where the work lives

- Working tree: `/Volumes/2TB/grok-vault/chotki-linux`
- Branch: local `linux`, created from `origin/codex/linux-port` at `0879899`
- Upstream: none yet. The branch was left without an upstream so a plain push cannot move `codex/linux-port`.
- Remote: `https://github.com/rjmac83/chotki.git`
- The `chotki-alpha` checkout stays on `main`. Its untracked design notes and mockups stay there.
- `codex/linux-port` stays at `0879899` until `linux` has been pushed and its Linux workflow is green. After that, the Codex branch is only a historical pointer.

The first commit on `linux` adds this branch to `.github/workflows/linux.yml` (the workflow currently runs on `main` and `codex/linux-port`) and is pushed with `git push -u origin linux`.

## Starting point

Phases 0 and 1 are done. An `amd64` `.deb` installs on a clean Ubuntu 24.04 runner, the helper reads the bundled core, and CI renders a review screenshot. Phase 2 has one real screen: Home. It shows a week, the selected day's commitments, completion, the bundled calendar's feast and fast cues, a settled-day mark, and the patristic saying on the daily artwork. Prayers, Reading, Progress, Library, Glossary, and Settings are labeled placeholders.

The macOS window is the reference for behavior and presentation. `core/` decides. QML draws and the Swift helper adapts. A screen that can be seen and cannot be used is unfinished.

## Rules that bind every slice

- Review runs and tests use the isolated review record. They never open `~/.local/share/Chotki` or the Mac record.
- The helper keeps calling `Practice`, `LiturgicalService`, `SQLiteStore`, and the other core types. New behavior goes into `core/` only when every platform should share it. A Linux-only shortcut in QML is a defect.
- The bundled calendar covers 2026–2031. orthocal.info is asked only outside that range, with the app's public User-Agent. Scripture is the bundled King James text.
- Reflections stay retired. Do not restore that route, its store tables, or its copy.
- The window is the product. Reminders, settings, navigation, and Quit work with no tray. A tray, if it is added at all, is a later optional menu and is never the only way in.
- There is no menu-bar companion. That is a Mac surface.
- The Linux label stays an alpha, independent of the Mac 1.0 beta build number, until Phase 5 says otherwise.
- Each slice updates `linux/PORT.md` with what was actually checked, and adds a bridge test or a Qt input test for the action it claims.

## Phase 2 — Finish the window

The Phase 2 gate in `PORT.md` still stands: a synthetic record can be created, edited, lived with for a day, exported, and restored through the window, and each screen has been reviewed beside the Mac at normal and scaled sizes.

Work in this order. Later slices depend on earlier destinations.

### 2.1 Bridge, before any new screen

The JSON boundary is already the right shape and it will not survive Library, the editor, and Reading as a pile of optional keys. Make it typed before it grows.

- Give requests and responses a small Codable schema in the helper, and a matching struct on the Qt side. Keep newline framing and the version field. Correlate each response with its request id. A late error must not clear a newer success.
- Reset the helper restart count when a `hello` succeeds. Today the third death in the life of the process gives up for good.
- Stamp `completedAt` when a rule is marked kept, as the Mac does. Unmarking still deletes the occurrence.
- A dispensed rule stays untoggleable. The error for that case says the day was not asked, which is different from a rule that is not on the day.
- Point `check_bridge.py` at a temporary review directory. The shared `~/.cache/chotki-linux-review` record is for human review, not for a test that writes.
- `--screenshot` fails if another review instance already holds the socket, and it waits until the snapshot fields are present, not merely until `hello` has returned.
- Add the missing Home icons for Fasting, Services, and Life.
- Show the whole saying. The card currently stops at two lines.
- Keep the fast-day color visible on the selected day.
- Add `linux` to the workflow branches and push the branch.

**Gate.** The existing Home actions still pass on Ubuntu 24.04 `amd64`: bridge check, sidebar and Home clicks, package install, and a screenshot that contains the sample commitments. A killed helper reconnects more than three times. The review test does not write the human review database.

**Checked on the ARM64 guest (2026-10-10):** the bridge test, including a temporary review directory, `completedAt`, and the dispensed-day refusal; the sidebar test; four helper deaths with a reconnect each time; an offscreen window that stayed up. The Ubuntu 24.04 `amd64` half of this gate is the GitHub workflow.

### 2.2 Prayers and the rope

Mac route: sidebar Prayers. With no prayer selected, the rope. A prayer rule opens `PrayerView` for that rule. The Psalter is a further page on this same route and is built with Reading.

- Draw the rope from `RopeCircleLayout` and play cues from `PrayerScreen.cue`. The platform draws and plays. It does not decide where a bead sits or which knots tock.
- Count knots, including the words on screen and the rope alone.
- Opening the app from a process that was not running plays the rope and the cross once. A second activation of an already-running instance does not. Reduced motion skips the mark.
- Morning and evening cards on Home will land here once 2.5 is done. The Jesus Prayer opens on the rope.
- The knot is complete. There is no applause.

**Gate.** A review record can count a prayer to its target, hear the bead cue, leave, and return to the same count. A Qt test clicks the rope and reads the new count back from the helper. Restarting the process plays the opening mark once.

### 2.3 Reading and the Psalter

Mac route: sidebar Reading, plus the Psalter reached from Prayers.

- Gospel, Epistle, Vespers, Matins, and the life of the day are separate sections. Opening a reading rule expands only the section it names.
- Scripture comes from the bundled King James file, paragraphs broken on the Bible's own marks, with a blank line between passages. No pilcrow.
- The life is the Prologue from Ochrid, shown for the observed church day, with the CC BY-SA 4.0 footer and the old-calendar and new-calendar dates. The text is not altered. There is no February 29 life.
- Completion of a reading is marked only after a deliberate scroll reaches the end of that section. Opening a disclosure does not count. Stood-down and dispensed days are left alone.
- The Psalter reads from `Psalter` in core, and a psalter rule completes through the same occurrence path as any other kept rule.

**Gate.** The review record can open each reading section, reach its end, and see that rule kept. A protocol test covers one scripture completion and proves a dispensed reading is not marked.

### 2.4 Library and the editor

This is the slice that makes the Phase 2 gate possible. Until it exists, the only rules on Linux are the ones the review seeder writes.

- Library lists `RuleLibrary` templates in core's order: services, prayer, reading, fasting, life, then rules of one's own. Nothing is on until it is taken on.
- Taking a rule on opens the editor first. The editor sets the recurrence, the time, and who suggested it, and only then saves.
- When a spiritual father's name is stored, the editor offers that name by a checkbox. Checking it records the current name on the rule. Clearing the name in Settings leaves names already stored on rules as they are.
- Pause and resume use activations. Archive is the removal path the Mac already has. Scoped edits use the core edit planner.
- Home's "Add a New Rule" and the dotted Add placard both open Library. The whole placard is the button.
- Search in the library finds a template by its title.

**Gate.** From an empty normal record in a temporary `XDG_DATA_HOME`, the window can take on two library rules, edit one, pause one, and see only the active rule on Home. The bridge test performs the same steps without Qt.

### 2.5 Home actions that need the other rooms

- The first click on a card opens its destination. Morning and evening prayers select their sequence. The Jesus Prayer opens the rope. A reading card opens the named section. Expansion, when the summary overflows, is a separate control and does not swallow that click.
- The card's further actions match the Mac menu: mark kept, mark kept late, clear the day, stand down, and open the editor. Standing down writes the skipped occurrence the Mac writes. Unticking deletes the row. It does not write a skip.
- When the last asked rule on a day becomes settled, the window says "Glory to God for all things" and then lets it fade. A day on which everything was stood down does not settle.
- The week strip and the card strip scroll on an ordinary wheel. The Today link follows core `TodayLink`: it appears once the visible week has moved off today.

**Gate.** The Qt navigation test, against the real helper and a temporary review record, marks a rule kept, stands one down, opens Prayers from a card, and returns to Home with the settled state the core reports.

### 2.6 Progress

- The report is `Practice.report`. Today is outside it. The window shows the same prose the Mac shows, including a paused rule removed from both sides of the count.
- No red, no "failed", no streak. Progress artwork stays still, with its quotation and caption inside the pane.
- The report can be opened at the 30-day range the Mac uses.

**Gate.** A fixture with one kept day and one missed day renders the core report's counts, and the missed day is not colored as a failure.

### 2.7 Glossary

- Entries come from the bundled glossary. A term in a prayer, a reading, or a rule opens the entry, and Back returns to the section that sent it.
- The glossary is introductory. The screen does not present it as a ruling.

**Gate.** A Qt test follows a term from a prayer to its entry and back to that prayer.

### 2.8 Settings, onboarding, and the record

Settings sections, in the Mac's order: You, Your Church, The Calendar, Reminders, Prayer Rope, Your Record, General.

- You: display name, spiritual father's name, and Clear under the father field.
- Your Church: the named church, or no church shown when none is named. An unnamed record follows the Orthodox Church in America. A church with no Akathist dates uses the OCA's and says so.
- The Calendar: old-style dates, and each fast and feast observance as hidden, shown, or observed. They start at shown.
- Reminders: the lead time and the master switch. Delivery itself is Phase 3. The switch must already persist.
- Prayer Rope: the choices the Mac stores for sound and count.
- Your Record: export a backup, restore by merge, and the daily backup directory under the XDG data dir. Restore merges. It does not replace.
- General: reduced motion, links to About Chotki and Privacy, and the Linux alpha version string.
- Onboarding is the first-run path. Someone who already has rules is not shown it again. The library is how a rule is chosen. The app states that it is not a parish.

**Gate.** A temporary normal record can set a name and a church, export, import into a second empty directory, and see the merged rules. Reduced motion persists across a helper restart.

### 2.9 Visual pass

Do this after the screens exist, so the pass covers the real window.

- Palette, XCharter for reading, sidebar width, and spacing taken from the Mac window.
- The month grid appears beside the day once the window is wide enough, and it shows one month at a time.
- Daily artwork pans slowly onto the curated focal point and holds there for the rest of that day. Use the existing saying order and focus metadata. Progress art does not pan.
- Icons are drawn in a scalable form, sharp on a hi-dpi display.
- Long card titles shrink to fit. Vertical pages fade at the edges instead of cutting on a hard line.
- Compare screenshots with the current Mac window at 1× and at 2×. Record any Linux gesture that differs, in this file, and keep the capability.

**Gate.** Side-by-side review of Home, Prayers, Reading, Library, Progress, Glossary, and Settings at both scales, with notes of what was accepted as different.

## Phase 3 — Session services

The window already has to be complete. This phase connects it to the session.

- Drive reminders from the core scheduler and ticker. A notification can mark the rule kept or snooze it. Withdrawing a notification follows the Mac.
- Sound uses the desktop audio path. Reduced motion and a missing audio device skip playback and leave the record correct.
- Launch at login is a desktop autostart entry the user can turn off from Settings.
- File dialogs for backup export and restore. Links open in the default browser.
- Keyboard shortcuts for the seven sidebar sections stay, and each new primary action gets a visible shortcut where the Mac has one.
- Closing the window quits. Quit stops the helper. A killed helper still reconnects, and the restart count still resets after a good `hello`.
- If a tray is added, detect that the shell has one. The menu is Open, Silence or Enable notifications, Settings, and Quit. No tray means the window is unchanged.

**Gate.** On a real GNOME session, a synthetic rule fires a notification, Mark kept writes the occurrence, and Quit leaves no helper behind. The same build then runs the reminder action on Plasma and on Xfce, or records the exact session where an action is unavailable and still completes from the window.

## Phase 4 — The package is the product

An alpha `.deb` already installs and opens. This phase makes that package the thing a reviewer can trust.

- Ship the optimized helper and window, the Swift runtime they actually link, the Qt and QML modules they actually load, SQLite, the core bundle, the calendar, prayers, artwork, fonts, licenses, the icon, and the `.desktop` file.
- Keep the runtime policy written down: Swift libraries bundled, Qt taken from Ubuntu 24.04 packages. Bump the package version on every `.deb` that is handed to someone.
- User data stays under `XDG_DATA_HOME/Chotki`. Uninstall removes `/usr/lib/chotki` and the desktop entry and leaves that directory in place. Upgrade and reinstall keep it.
- Confirm the LGPL obligations for the Qt modules that are linked, and ship the notices beside the existing Swift, XCharter, and app licenses.
- The clean-install CI job runs the synthetic daily flow against the installed package: take on a rule, mark it kept, export, restore into a fresh data directory.

**Gate.** A clean Ubuntu 24.04 `amd64` VM with no compilers installs the `.deb`, runs that flow, upgrades without losing the record, and uninstalls without deleting it.

## Phase 5 — Accept or hold

- Run the installed package on GNOME, Plasma, and Xfce. Check startup, scaling, fonts, focus, scrolling, resize, notifications, dialogs, sound, the theme, reduced motion, and the path with no tray.
- Run the core suite and the Linux UI tests on the candidate.
- Inspect the architecture, `ldd`, the package file list, and the licenses.
- A person compares the screenshots and uses the window with a mouse and a keyboard.

**Gate.** No missing daily action and no record corruption. The `.deb` target is the one that was installed clean. Differences across desktops are written down. Only then decide whether to publish a Linux alpha. Until that decision, the branch stays source plus a CI artifact.

## Package targets

The release artifact is an `amd64` `.deb` built on Ubuntu 24.04. That job stays in GitHub CI. This ARM guest does not cross-compile it.

ARM is a second package of the same app, built natively on the Ubuntu guest. The 2026-10-10 guest build produced an `aarch64` shell and helper there, and an offscreen launch stayed up. An `arm64` `.deb` follows the same packaging script once the window is complete.

Linux on mobile is the same `aarch64` application with a layout that fits a phone-sized screen. It is not a third codebase. It waits until the desktop window can carry a day.

## Out of scope for this alpha

- Fedora, Arch, a Flatpak, or an AppImage.
- A tray that hides the window.
- Accounts, sync, or any network call besides orthocal.info for dates outside the bundled calendar.
- New artwork. The existing library and its focal metadata are the set. Additions need a separate approval.
- The retired reflections journal.

## First slice, when work begins

Slice 2.1 only. No new room of the app until that gate is green.
