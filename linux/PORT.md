# Chotki for Linux — phased port plan

**Status:** Phase 0 is complete. Phase 1 foundation is in progress. The shell and helper build on ARM64 Ubuntu 26.04 and `amd64` Ubuntu 24.04 CI. An early `arm64` alpha `.deb` built, installed, and launched on the development VM; an `amd64` package and clean-install CI check are pending. No Linux release exists yet.

## Decision and scope

- Build one Linux desktop app with **Qt 6 and QML**, using the existing Swift `ChotkiCore` as the source of behavior. Use the current macOS app as the functional and visual reference. Do not duplicate core decisions in QML.
- Target a **window-first** experience. GNOME on Ubuntu is the primary design and acceptance environment; verify the same app on KDE Plasma and Xfce. A desktop environment does not require a separate binary or front end.
- Deliver a `.deb` for a declared Ubuntu/Debian baseline and architecture. A `.deb` does not cover Fedora, Arch, or every Linux distribution; other package formats are outside the first release.
- Treat the tray as an optional enhancement. GNOME may not expose it without an extension, so reminders, settings, navigation, and Quit must all be reachable from the main window.
- Keep a Linux alpha label independent of the macOS release label. Do not publish until the final acceptance gate passes.

## Phase 0 — Feasibility spike and decisions

**Result (2026-10-07):** A Qt 6.10.2/QML window ran on Ubuntu 26.04.1 ARM64 and exchanged JSON requests with a persistent Swift 6.4 process importing canonical `ChotkiCore`. It displayed a core date calculation and Psalm 1 from the core bundle, saved a synthetic value through `SQLiteStore`, received a structured error, and read the saved value after relaunch. The Qt window was visually inspected and clicked in UTM; shutdown now closes the helper cleanly. The canonical core suite passed all 453 tests on the VM once its cross-platform reference paths were linked into the isolated test workspace. Source and reproduction steps are in [`spike/README.md`](spike/README.md). The bridge is feasible as a long-lived helper process, with protocol versioning and recovery left for Phase 1.

**Release direction:** First package architecture is `amd64` for Intel/AMD Linux. The ARM64 VM is the development and review environment. Ubuntu 24.04 LTS is the candidate minimum `.deb` baseline, subject to a real build and clean-install test there; no compatibility claim follows from this Ubuntu 26.04 ARM64 spike. The window is the required surface; a tray remains optional. Qt Quick and Qt QML have LGPLv3 options under Qt's open-source licensing, but the final module inventory and distribution obligations belong in Phase 4.

**Work:** Establish an interactive Linux desktop test environment. The existing UTM path described in `../CLAUDE.md` provides a native ARM64 Ubuntu guest for rapid visual and input review; release architecture must be validated separately. Build a small Qt/QML window that calls a real `ChotkiCore` operation, reads a bundled resource, and persists a synthetic SQLite record through a narrow Swift-to-Qt boundary. Evaluate a C-compatible boundary or another maintained interop path by compiling and running it, not by assuming it works. Confirm Qt version, license obligations, Ubuntu/Debian baseline, initial CPU architecture, and whether tray support is wanted later.

**Gate:** The window works in the Linux guest; Swift calls and error handling work in both directions; resources and synthetic persistence survive relaunch; the bridge and package baseline are recorded. Stop and revise the approach if this cannot be demonstrated without an unmaintainable bridge.

## Phase 1 — Foundation and delivery loop

**Progress (2026-10-07):** The versioned Swift helper and Qt/QML shell build and launch on Ubuntu 26.04.1 ARM64. Review storage is separate from the normal XDG data path. The shell shows the Chotki sidebar, palette, bundled XCharter font, greeting, and core date. A second launch activates the existing instance, a killed helper restarts and reconnects, and closing the window leaves no helper behind. GitHub Actions [run 37696472735](https://github.com/rjmac83/chotki/actions/runs/37696472735) passed an `amd64` shell build, bridge/core check, and headless launch on Ubuntu 24.04. A Qt input test clicks the Prayers route successfully on ARM64; it is being added to CI. Physical sidebar clicks are not yet verified because input through the UTM session did not produce click events even with a full-window tracing area. The shell body is a placeholder pending Phase 2. See [app/README.md](app/README.md).

**Work:** Create `linux/` sources and build definitions without copying canonical core. Put app orchestration and Linux adapters behind the existing core protocols. Set up XDG-appropriate data, config, and cache paths, single-instance behavior, and explicit review/test storage that cannot open a live record. Build CI for the Linux app and retain the existing core portability guard and Linux tests. Add a repeatable guest build, launch, screenshot, and input loop.

**Gate:** A clean Linux build launches a branded empty shell; core tests pass; a synthetic record is isolated; a fresh reviewer can reproduce both a screenshot and a real keyboard/mouse interaction.

## Phase 2 — Main interface and core actions

**Work:** Recreate the macOS window structure and Chotki palette, typography, artwork, spacing, and motion in QML. Implement Home, calendar navigation, Prayers and rope, Rule and editor, Reading and Psalter, Library, Progress, Glossary, onboarding, and Settings. Wire every visible action to core operations, including scoped edits, pause/resume, completion, stand-down, search, and backup export/merge restore. Inventory the macOS controls and routes deliberately; a screen that renders but cannot be reached or acted on is incomplete.

**Gate:** A synthetic record can be created, edited, used across the full daily flow, exported, and restored through the visible UI. Screen-by-screen visual review and physical input review pass at normal and scaled display sizes. Content, attribution, and behavior match the macOS reference; any intentional Linux-specific gesture is documented without dropping capability.

## Phase 3 — Linux services and lifecycle

**Work:** Implement timer-driven reminders with the core scheduler and ticker, desktop notifications and supported actions, withdrawal/snooze behavior, sound playback, launch at login, file dialogs, links, keyboard shortcuts, theme and reduced-motion handling, and safe close/Quit behavior. Use standard desktop integration where possible. If a tray is added, detect its availability and never hide the only usable window when it is absent. Test GNOME first, then Plasma and Xfce, under the display protocols actually used by the chosen distributions.

**Gate:** Reminders and their actions work on a real desktop session; denied or unavailable notification features fail gracefully; relaunch and close/Quit never strand a running app; all essential functions work without a tray.

## Phase 4 — `.deb` and installation

**Work:** Package the optimized executable, matching Swift and Qt runtime dependencies, QML modules/plugins, SQLite linkage, bundled calendar and prayer resources, artwork, fonts, license notices, icon, and `.desktop` entry. Choose and document system-library versus bundled-runtime policy after testing on a clean target installation. Store user data in the user's home directory, outside the package payload. Verify install, upgrade, uninstall, and reinstall without record loss. Produce the first `.deb` only for the tested distribution baseline and architecture.

**Gate:** A clean VM with no development tools can install and launch the `.deb`; all resources load; the installed app passes the synthetic daily flow; upgrade preserves settings and data; uninstall removes app files while leaving user data available for reinstall.

## Phase 5 — Cross-desktop acceptance and alpha decision

**Work:** Run the installed package on GNOME, Plasma, and Xfce. Check startup, scaling, fonts, keyboard focus, scrolling, window resizing, notifications, file dialogs, sound, theme, reduced motion, and the no-tray path. Compare actual screenshots and interactions with the current macOS app. Run the full core suite and Linux UI/lifecycle checks on the release candidate. Inspect architecture, linked libraries, payload contents, and licensing. Use only synthetic records in automated and review runs.

**Gate:** No critical capability or data-integrity gap remains; the declared `.deb` target works from a clean install; cross-desktop differences are documented; a human has reviewed visual quality and real interactions. Only then decide whether to publish an alpha.

## Main risks to resolve early

| Risk | Why it matters | Earliest proof |
|---|---|---|
| Swift–Qt boundary | It can dominate the port's complexity and maintenance cost. | Phase 0 real core call, resource load, persistence, and error path |
| Runtime packaging | A developer-machine build can fail on a clean distribution. | Phase 0 dependency inventory; Phase 4 clean-install test |
| Desktop integration | GNOME tray behavior and notification actions vary by session. | Phase 3 real-session checks; window always usable |
| Visual parity | QML can be functional while losing Chotki's carefully tuned presentation. | Phase 2 side-by-side screenshots and input review |
| Architecture coverage | ARM64 VM success does not prove an x86_64 `.deb`. | Phase 4 clean install on each released architecture |

## Reference material

- `../CLAUDE.md`, `../retrospective.md`, `../project-rules.md`, and the current macOS implementation define existing behavior and working rules.
- `../core/` is the canonical Swift logic; its Linux CI tests are a foundation, not proof that a Linux UI works.
- Qt's [Linux deployment guide](https://doc.qt.io/qt-6/linux-deployment.html) covers runtime dependencies and `.deb` creation. Its [tray documentation](https://doc.qt.io/qt-6/qsystemtrayicon.html) describes GNOME limitations. The [freedesktop desktop-entry](https://specifications.freedesktop.org/desktop-entry/latest/) and [notification](https://specifications.freedesktop.org/notification/latest/) specifications guide desktop integration.
