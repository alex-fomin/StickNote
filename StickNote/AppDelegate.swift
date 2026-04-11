import Cocoa
import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftData

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private(set) lazy var sparkleUpdaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        Self.shared = self

        KeyboardShortcuts.onKeyUp(for: .createNote) {
            AppState.shared.openNewNote()
        }
        KeyboardShortcuts.onKeyUp(for: .createNoteFromClipboard) {
            AppState.shared.openNewNoteFromClipboard()
        }
        KeyboardShortcuts.onKeyUp(for: .showHideNotes) {
            AppState.shared.toggleNotesVisibility()
        }

        AppState.shared.processDueScheduledUnhides()
        AppState.shared.openAllNotes()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateFirstLaunchFlagIfUpgradingFromVersionWithoutKey()
        guard !Defaults[.hasCompletedFirstLaunch] else { return }
        DispatchQueue.main.async {
            AppState.shared.presentSettingsWindow()
            Defaults[.hasCompletedFirstLaunch] = true
        }
    }

    /// If the key was never written, treat installs that already have notes as not first launch (app upgrade).
    private func migrateFirstLaunchFlagIfUpgradingFromVersionWithoutKey() {
        let key = Defaults.Keys.hasCompletedFirstLaunch.name
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        let noteCount = (try? AppState.shared.context.fetchCount(FetchDescriptor<Note>())) ?? 0
        if noteCount > 0 {
            Defaults[.hasCompletedFirstLaunch] = true
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppState.shared.presentSettingsWindow()
        return true
    }

    static func checkForUpdates() {
        shared?.sparkleUpdaterController.checkForUpdates(nil)
    }
}
