import AppKit
import Sparkle

/// Owns the Sparkle updater: background checks against the appcast feed
/// (configured via SUFeedURL / SUPublicEDKey in Info.plist) plus a manual
/// "Check for Updates…" entry point from the menu bar.
@MainActor
final class UpdaterController: NSObject, ObservableObject {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController

    override init() {
        // startingUpdater: true wires automatic background checks immediately.
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        super.init()
    }

    /// User-initiated check (shows "you're up to date" if nothing is newer).
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
