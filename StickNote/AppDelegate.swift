import Cocoa
import Defaults
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {

        KeyboardShortcuts.onKeyUp(for: .createNote) {
            AppState.shared.openNewNote()
        }
        KeyboardShortcuts.onKeyUp(for: .createNoteFromClipboard) {
            AppState.shared.openNewNoteFromClipboard()
        }
        KeyboardShortcuts.onKeyUp(for: .showHideNotes) {
            AppState.shared.toggleNotesVisibility()
        }

        AppState.shared.openAllNotes()
    }
}
