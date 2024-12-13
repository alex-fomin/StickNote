import KeyboardShortcuts
import SwiftUI

struct MainMenu: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Add new note") {
            AppState.shared.openNewNote()
        }
        .keyboardShortcut(
            KeyboardShortcuts.Shortcut(name: .createNote)?.toKeyboardShortcut()
        )

        Button("Pasre note from clipboard") {
            AppState.shared.openNewNoteFromClipboard()
        }
        .disabled(
            !NSPasteboard.general.canReadItem(withDataConformingToTypes: [
                NSPasteboard.PasteboardType.string.rawValue
            ]))
        .keyboardShortcut(
            KeyboardShortcuts.Shortcut(name: .createNoteFromClipboard)?.toKeyboardShortcut()
        )
        Divider()
        Button("Settings") { openSettings() }
        Button("Exit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("Q")
    }
}
