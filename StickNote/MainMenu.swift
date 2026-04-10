import AppKit
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
        .disabled(!NoteClipboardImage.pasteboardCanCreateNote())
        .keyboardShortcut(
            KeyboardShortcuts.Shortcut(name: .createNoteFromClipboard)?.toKeyboardShortcut()
        )
        Divider()
        Button("Note list...") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "note-list")
        }
        Button("Show all hidden notes") {
            AppState.shared.requestRevealHiddenNotesInList()
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "note-list")
        }
        Divider()
        Button($model.isNotesHidden.wrappedValue ? "Show notes" : "Hide notes") {
            AppState.shared.toggleNotesVisibility()
        }
        .keyboardShortcut(
            KeyboardShortcuts.Shortcut(name: .showHideNotes)?.toKeyboardShortcut()
        )
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("Q")
    }
}
