# Mandatory Windows build environment

Saved 2026-10-03. Applies to every future Windows compilation, build and test
in this repository. Supersedes earlier shared-drive SQLite and build rules.
Host: Windows 11 ARM64 VM, UTM on Apple Silicon.
Target: **x86_64-unknown-windows-msvc**.

## 1. Compiler environment

Before ANY swiftc or swift build command, set in the same PowerShell session:

```powershell
$env:MIMALLOC_DISABLE_REDIRECT = "1"
$env:SWIFT_DRIVER_USE_FRONTEND = "0"
```

These are mandatory to bypass the observed allocator access-violation crashes.

## 2. SQLite and C dependencies

Use vcpkg x64 exclusively:

- Header and module map: C:\vcpkg\installed\x64-windows\include
- Import library: C:\vcpkg\installed\x64-windows\lib
- SQLite DLL: C:\vcpkg\installed\x64-windows\bin\sqlite3.dll

```powershell
swiftc -target x86_64-unknown-windows-msvc -I C:\vcpkg\installed\x64-windows\include -L C:\vcpkg\installed\x64-windows\lib test.swift -o test.exe
swift build --triple x86_64-unknown-windows-msvc --build-system native -Xcc -IC:\vcpkg\installed\x64-windows\include -Xlinker -LC:\vcpkg\installed\x64-windows\lib
```

Never compile a default target. Do not use unsupported -static-swift-stdlib.
Use the native backend in addition to the triple: the default Swift 6.4 backend
compiled ARM64 despite the requested target during this session. The app's
compile-time architecture guard caught the error.

## 3. Bundle DLLs after every build

Before testing, copy SQLite and the PE-verified x86_64 runtime DLLs from
C:\swift-x64-runtime alongside every built executable:

```powershell
Copy-Item "C:\vcpkg\installed\x64-windows\bin\sqlite3.dll" -Destination "$OutputDir\" -Force
```

Discover .dll files recursively under C:\swift-x64-runtime and copy those with
PE machine 0x8664 into $OutputDir. Verify swiftCore.dll and the other runtime
DLLs are present. Do not copy ARM64 runtime DLLs or confuse extraction-tool DLLs
with a complete Swift runtime. Match its version to the SDK. The current helper
selects C:\swift-x64-runtime\6.4.0\extracted exclusively. The historical 6.0
runtime passed the tiny SQLite example but failed to load the full 6.4 app with
0xC0000139 (missing entry point). No compiler installation needs to be changed.

## 4. Local storage and execution isolation

Edit sources/configuration on Mac, stage canonical core using prepare-core.py,
and synchronize windows/ to C:\workspace-build before every build/test loop.
Build and execute only on local C: storage; never on shared Z:. Keep host and
guest source copies synchronized, including deletions/renames. Do not edit guest
source independently. Z:\windows is only a source mount. The current SSH helper uploads a verified
public-source archive from the Mac to native C: storage before each scripted
build, bypassing stale WebDAV reads and its large-file limit. Upload the separate
artwork archive after prepare-assets.py; build-vm.ps1 verifies its catalog.

Execute from the output directory with an isolated PATH:

```powershell
$env:PATH = "$OutputDir;C:\Windows\system32;C:\Windows"
Set-Location $OutputDir
```

Never use the system PATH as-is to execute/test x86_64 binaries: it includes
ARM64 Swift runtime paths, including C:\Program Files\Swift\runtime-development\usr\bin.

## 5. Verification protocol

For every requested project build/test, verify all four gates:

1. swift build returns exit code 0.
2. Generated executable PE machine is 0x8664 (AMD64).
3. SQLite and all required x86_64 Swift DLLs are beside the executable.
4. Execution under Windows Prism emulation succeeds without 0xC0000005 or
   0xC000007B; record the exit code and expected output.

Build success alone is not an end-to-end test pass. Use synthetic practice and
public fixtures; never open or copy live Chotki data.
