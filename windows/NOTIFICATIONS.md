# Windows notification integration

The compatibility helper in Sources/WindowsUI/Notifications is the MIT-licensed
Microsoft desktop notification sample recommended by the Windows WRL guide.
Pinned upstream: WindowsNotifications/desktop-toasts, commit
53783524b3f594d0ddf8ae85bf7d5442c9bb4075, CPP-WRL/DesktopToastsCppWrlApp.
Its complete MIT license is included beside the source. Two generic Win32 calls
are explicitly suffixed W so the helper compiles independently of Visual
Studio project-wide Unicode defines.

Primary references:
- https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast-desktop-cpp-wrl
- https://learn.microsoft.com/en-us/windows/win32/shell/enable-desktop-toast-with-appusermodelid

ChotkiCore Scheduler and ReminderTicker remain responsible for timing, quiet
hours, stale suppression, settled occurrences and snoozing. The Windows adapter
provides delivery, withdrawal and COM action activation. Automated UI reviews
use an in-memory delivery surface; real notification acceptance uses a separate
temporary app identity and never the user's Chotki record.
