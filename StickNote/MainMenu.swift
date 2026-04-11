import AppKit
import KeyboardShortcuts
import SwiftUI

struct MainMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppStateModel.self) private var model

    var body: some View {
        Group {
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
            Button(model.isNotesHidden ? "Show notes" : "Hide notes") {
                AppState.shared.toggleNotesVisibility()
            }
            .keyboardShortcut(
                KeyboardShortcuts.Shortcut(name: .showHideNotes)?.toKeyboardShortcut()
            )
            Button("Settings...") {
                AppState.shared.presentSettingsWindow()
            }
            Button("Check for Updates…") {
                AppDelegate.checkForUpdates()
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("Q")
        }
    }
}
