import Foundation
import OSLog
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for registering Babel as a login
/// item. Reading `isEnabled` queries the system state; toggling may prompt the
/// user for Login Items permission the first time.
enum LaunchAtLogin {
    private static let log = Logger(subsystem: "com.babel.app", category: "launch-at-login")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
                log.info("registered as login item")
            } else {
                try service.unregister()
                log.info("unregistered as login item")
            }
        } catch {
            log.error("failed to toggle login item: \(String(describing: error), privacy: .public)")
        }
    }
}
