import AppKit
import Foundation
import OSLog
import Sparkle

/// Thin wrapper around Sparkle 2.x's `SPUStandardUpdaterController`. Held by
/// the `AppDelegate` so the controller's lifetime matches the app's.
///
/// Sparkle is driven entirely by Info.plist keys (`SUFeedURL`,
/// `SUPublicEDKey`). Until the first signed release is published and the
/// public key is populated, `checkForUpdates()` is a no-op at runtime —
/// Sparkle rejects unsigned feeds.
@MainActor
final class UpdateController: NSObject {
    private static let log = Logger(subsystem: "com.babel.app", category: "updater")

    private let controller: SPUStandardUpdaterController

    override init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        Self.log.info("Sparkle updater started (feed=\(Self.feedURLString, privacy: .public))")
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    /// Triggered by the "Check for Updates…" menu item. Sparkle owns the UI.
    func checkForUpdates() {
        Self.log.info("checkForUpdates invoked")
        controller.checkForUpdates(nil)
    }

    private static var feedURLString: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "(none)"
    }
}
