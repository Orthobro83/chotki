# Windows port instructions

- Read and follow `BUILD-ENVIRONMENT.md` for every Windows compilation/build/test. It is the current mandatory environment and supersedes all earlier workaround commands in historical notes.
- Before any swiftc or swift build, set MIMALLOC_DISABLE_REDIRECT=1 and SWIFT_DRIVER_USE_FRONTEND=0 in that PowerShell session.
- Explicitly target x86_64-unknown-windows-msvc; never use default builds or -static-swift-stdlib.
- SQLite comes exclusively from C:\vcpkg\installed\x64-windows (include, lib, bin).
- Edit source/configuration on Mac, stage core using `tools/prepare-core.py`, and synchronize Z:\windows to C:\workspace-build. Build and execute on C: only. Canonical shared logic stays in core/, never generated windows/shared-core/.
- After every build, bundle PE-verified x64 runtime DLLs from C:\swift-x64-runtime plus vcpkg sqlite3.dll beside each executable. Check executable/DLL architecture and run with PATH containing only its output directory, C:\Windows\system32 and C:\Windows.
- Verify build exit 0, executable PE 0x8664, required DLLs present, and successful Prism execution without allocator/image-format crashes.
- Select SwiftPM's native backend alongside the explicit triple. Match bundled runtime DLLs to the compiler SDK version; the current SDK needs the separately extracted Swift 6.4 runtime, not the historical 6.0 runtime.
- Use tools/verify-ui-desktop-vm.ps1 for visual review: SSH runs in noninteractive session 0. Capture only the synthetic Chotki window; remove temporary review tasks after use.
- SSH uses `tools/run-vm.py` and ignored `connection.local.md`. Never commit credentials, host keys or private diagnostics; never force-add ignored local files.
- Preserve current macOS capabilities, using the current macOS app as the primary behavior and visual reference. Reuse ChotkiCore decisions rather than duplicating them in the UI.
- Use synthetic practice and public fixtures. Never open or copy live Chotki data.

- Do not create or publish a Windows release candidate until the macOS parity port is finished. ARM64 remains deferred.
