import Foundation

/// macOS uses SMAppService, Windows a registry Run key, Linux a .desktop entry.
/// Core never knows which.
public protocol LaunchAtLogin: Sendable {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}
