import KeyboardShortcuts
import SwiftUI

struct MainMenu: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    @State var model: AppStateModel

    var body: some View {
        Button("New note") {
            AppState.shared.openNewNote()
        }
        .keyboardShortcut(
            KeyboardShortcuts.Shortcut(name: .createNote)?.toKeyboardShortcut()
        )

        Button("Paste note") {
            AppState.shared.openNewNoteFromClipboard()
        }
        .disabled(
            !NSPasteboard.general.canReadItem(withDataConformingToTypes: [
                NSPasteboard.PasteboardType.string.rawValue,
                NSPasteboard.PasteboardType.rtf.rawValue,
                NSPasteboard.PasteboardType.rtfd.rawValue
            ])
        )
        .keyboardShortcut(
            KeyboardShortcuts.Shortcut(name: .createNoteFromClipboard)?.toKeyboardShortcut()
        )
        Divider()
        Button("Note list..."){
            openWindow(id: "note-list")
        }
        Divider()
        Button($model.isNotesHidden.wrappedValue ? "Show notes" : "Hide notes") {
            AppState.shared.toggleNotesVisibility()
        }
        .keyboardShortcut(
            KeyboardShortcuts.Shortcut(name: .showHideNotes)?.toKeyboardShortcut()
        )
        Button("Settings...") { openSettings() }
        Button("Exit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("Q")
    }
}
