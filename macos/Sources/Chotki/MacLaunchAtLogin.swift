import Foundation
import ServiceManagement
import ChotkiCore

/// Windows will use a registry Run key and Linux a .desktop entry.
/// Core never learns which.
struct MacLaunchAtLogin: LaunchAtLogin {

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
