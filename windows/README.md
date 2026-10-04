# Chotki for Windows

Windows **alpha-rc2-build31** targets x86_64 Windows 11. The current macOS app
is the visual and functional specification. Full parity is the release gate;
ARM64 is deferred.

The SwiftPM executable combines canonical ChotkiCore with a native Win32 UI.
Home includes grouped/collapsible navigation, week/month selection, separate
rule-card open/expand/complete actions and the original 365-image rotation.
Calendar retrieval caches to SQLite and posts native messages to repaint arriving
data. The editor uses core recurrence/scoped edits; Settings includes JSON
export/merge restore and daily backups. Reading uses shared texts and distinguishes
deliberate end scrolling from programmatic navigation. Styled readers preserve
rubrics, headings, emphasis and source links. Prayer glossary links open an
in-app detour with search and related terms, preserving the reading position.
Reading sections expand independently with their text directly beneath each
heading. The Psalter groups appointed kathismata by service and offers all twenty
for manual reading; completion follows the last verse, never a closed heading.
Prayers now includes the large count, knot dots, grouped selection, rope-only
mode, manual visibility and target/reset controls. Space counting rejects held
repeat and modifiers and remains isolated from menus, glossary and other pages.
The tray provides only Open Chotki, Silence/Enable notifications, Settings and Quit. Closing the window
keeps Chotki available in the tray; Quit removes the icon and exits. The toggle
persists the shared notification preference and agrees with Settings.

Library, Progress and Settings now use their Mac section order and shared
content. New templates open the editor first; custom-rule caution is remembered.
Progress includes the stationary Mac artwork and a reusable ninety-day window.
The canonical first-run welcome and synthesized tick/chime are implemented.
Windows reminders reuse the core scheduler/ticker and provide native toasts,
complete/snooze actions, withdrawal and due attention. A temporary-identity VM
smoke test verified actual Windows notification history delivery and COM actions.

Remaining work includes measured expansion, reading ornaments, artwork and
opening motion/reduced motion, rope transitions, responsive editor polish,
physical input/accessibility, installed startup acceptance and packaging. See [PORT.md](PORT.md).

## Build and verify

Follow [BUILD-ENVIRONMENT.md](BUILD-ENVIRONMENT.md) for every compilation and test.
Source stays on Mac; canonical core stays in `../core`. `shared-core` is generated.

```sh
python3 windows/tools/prepare-core.py
python3 windows/tools/prepare-assets.py
python3 windows/tools/run-vm.py --upload windows/assets.zip
python3 windows/tools/run-vm.py windows/tools/verify-vm.ps1
python3 windows/tools/run-vm.py windows/tools/verify-ui-desktop-vm.ps1
python3 windows/tools/run-vm.py windows/tools/verify-notifications-vm.ps1
```

The SSH helper reads ignored `connection.local.md` fields `Host`, `Username` and
`Password`. Never commit credentials or host keys. It uploads a public-source
archive, verifies SHA-256 and synchronizes to native `C:\workspace-build`, bypassing
stale shared-drive reads. Its manifest removes obsolete compiler inputs while
preserving build caches and staged artwork. Re-upload `assets.zip` whenever its
catalog fingerprint changes. Do not edit guest sources independently.

PowerShell sets `MIMALLOC_DISABLE_REDIRECT=1` and `SWIFT_DRIVER_USE_FRONTEND=0`
before every compiler call. Never use default architecture or static runtime flags.

```powershell
swift build --triple x86_64-unknown-windows-msvc --build-system native -Xcc -IC:\vcpkg\installed\x64-windows\include -Xlinker -LC:\vcpkg\installed\x64-windows\lib
```

This toolchain needs the native backend to honor the triple. Build/run on C: only.
Helpers bundle matching Swift 6.4 and SQLite DLLs, verify AMD64 PE headers and isolate
the execution PATH. Runtime extraction tools unpack x64 installer DLLs without
changing the host compiler installation.

## Tests and review

`--self-test` checks SQLite/settings, backup and all 151 Psalter resources.
`--ui-smoke` drives native controls with an in-memory synthetic record. `--review`
opens synthetic practice. Normal launch stores a Windows record under
`%LOCALAPPDATA%\Chotki`; tests never open live records.

```sh
python3 windows/tools/prepare-test-fixtures.py
python3 windows/tools/run-vm.py windows/tools/test-core-vm.ps1
python3 windows/tools/run-vm.py windows/tools/verify-ui-desktop-vm.ps1
```

Desktop review uses a temporary interactive scheduled task, captures the synthetic
app window on native `C:\workspace-build\reviews`, archives it, then removes the
task. Retrieve the reported archive with `run-vm.py --download <remote-file>
windows/.build/reviews/<archive-name>.zip` and unpack it locally. Downloads are
limited to the native build workspace; review artifacts stay ignored. SSH's session 0
cannot supply reliable screenshots. Native control checks complement visual review;
physical input and native accessibility have also passed their separate harness.
Real x86_64 hardware acceptance remains outside the ARM64 VM.

## Fonts and artwork

Four licensed XCharter cuts follow the Mac's Charter fallback. Keep
[Fonts/LICENSE.txt](Fonts/LICENSE.txt) with redistributed fonts. Apple's Iowan face
is not bundled. Artwork, focal metadata and original notices come from Mac resources.


## Windows packaging and startup review

Run `prepare-branding.py` on the Mac after changing the canonical mark or version.
`build-vm.ps1 -Configuration release` creates a GUI executable with embedded icon,
version and per-monitor-DPI manifest. `verify-release-vm.ps1` runs the complete
synthetic desktop suite against that optimized executable; `verify-input-vm.ps1`
uses real mouse/keyboard events and native accessibility providers.

`package-vm.ps1` builds a draft payload and integrity manifest without publishing
it. `verify-lifecycle-vm.ps1` tests the packaged startup/second-instance/animation
adapters in a private namespace. `install-windows.ps1` validates and installs a
payload for the current user and creates Desktop/Start menu shortcuts. Its launch
script excludes ARM64 toolchain paths. Program updates preserve the separate
practice record. Draft assembly is not a release-candidate declaration.

The current alpha is installed on the VM with a Chotki Desktop icon. Its optimized
desktop, physical input/accessibility, native notification, assembled-payload
and installed lifecycle gates passed under Prism. Synthetic visual checks cover
Library scrolling, editor state, and Home resizing. User acceptance and physical
x86_64 hardware validation follow; native ARM64 remains deferred. This alpha
build has not been published as a GitHub release.
