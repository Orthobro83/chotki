# Phase 0 Linux bridge proof

This is a disposable technical proof, not the Chotki Linux application. It
establishes that Qt/QML can drive the canonical Swift core on a GNOME desktop.
The UI starts one long-lived Swift helper using Qt's `QProcess` and exchanges one
JSON request/response per line. That boundary avoids a fragile Swift/C++ ABI
layer and keeps `core/` unchanged. Phase 1 still needs protocol versioning,
helper recovery, and typed commands before it can become application wiring.

## Environment used

- Ubuntu Desktop 26.04.1 ARM64 in UTM, GNOME on Wayland
- Swift 6.4.0 installed with official `swiftly`
- Ubuntu Qt 6.10.2, CMake, Ninja, SQLite development headers
- UTM's `share` 9p folder mounted read-only at `/mnt/utm`; all build output is
  copied to and produced under `/home/ryan/chotki-phase0`
- Sample record only: `/home/ryan/.cache/chotki-phase0/record.sqlite`

## Reproduce in the guest

From an Ubuntu terminal with Swift, Qt development packages, CMake, Ninja, and
SQLite headers installed:

```sh
mkdir -p "$HOME/chotki-phase0/core" "$HOME/chotki-phase0/linux"
cp -a /mnt/utm/chotki-1/core/Package.swift \
  /mnt/utm/chotki-1/core/Sources /mnt/utm/chotki-1/core/Tests \
  "$HOME/chotki-phase0/core/"
cp -a /mnt/utm/chotki-1/linux/spike "$HOME/chotki-phase0/linux/"
swift build --package-path "$HOME/chotki-phase0/linux/spike/bridge" -j 1
cmake -S "$HOME/chotki-phase0/linux/spike/ui" \
  -B "$HOME/chotki-phase0/linux/spike/ui/build" -G Ninja
cmake --build "$HOME/chotki-phase0/linux/spike/ui/build" -j 2
bridge_bin="$(swift build --show-bin-path \
  --package-path "$HOME/chotki-phase0/linux/spike/bridge")/ChotkiLinuxSpikeBridge"
"$HOME/chotki-phase0/linux/spike/ui/build/chotki-linux-spike" "$bridge_bin"
```

Launch the final command from a desktop terminal, or supply that desktop
session's Wayland and D-Bus environment when launching over SSH. The bridge
only opens its own synthetic database path; it never consults the Mac record.

## Observed proof

- The UI displayed `2026-10-08` from `CalendarDate.adding(days:)` and six
  bundled verses for Psalm 1 from `Psalter.psalm(1)`.
- A value saved through the window appeared in the window after a fresh launch.
- An unsupported command produced an error in the window, which cleared after
  a successful save.
- The rebuilt window closed with no remaining UI or Swift helper process.
- The canonical core suite passed on this VM: 453 tests in 81 suites. Its
  cross-platform parity tests read files outside `core/`, so the isolated
  test workspace linked the repository's Android, iOS, macOS, Windows,
  content, and checklist paths read-only from `/mnt/utm/chotki-1`.
- Rendering worked despite nonfatal Mesa/EGL warnings from the VM graphics
  stack. A screenshot from inside the SSH Wayland session failed; the window
  was inspected through UTM on the Mac.

This validates the bridge and GNOME rendering on **ARM64 Ubuntu 26.04** only.
It does not validate an `amd64` build, Ubuntu 24.04, KDE Plasma, Xfce, runtime
bundling, or a `.deb`. Those checks remain in later phases.

## Decisions carried forward

- Use one persistent Swift helper process rather than direct Swift/C++ ABI
  interop, unless Phase 1 measurements expose a concrete limitation.
- Build and test the first release package for Ubuntu 24.04 LTS `amd64` if its
  Qt/Swift baseline permits; otherwise revise and document the baseline before
  packaging. The UTM ARM64 guest does not establish `amd64` compatibility.
- Keep the main window fully usable without a tray.
- Dynamically linked Qt Quick/QML modules offer an LGPLv3 route. Audit every
  shipped module and satisfy the applicable notice, source, and relinking
  obligations before distribution; see [Qt licensing](https://doc.qt.io/qt-6/licensing.html).
