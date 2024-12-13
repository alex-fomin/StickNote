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
        Divider()
        Button("Settings") { openSettings() }
        Button("Exit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("Q")
    }
}
