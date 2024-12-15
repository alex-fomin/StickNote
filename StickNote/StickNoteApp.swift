import Foundation
import KeyboardShortcuts
import SwiftData
import SwiftUI

@main
struct StickNoteApp: App {
    init() {
        AppState.shared.openAllNotes()
    }
    var body: some Scene {
        MenuBarExtra {
            MainMenu()
        } label: {
            HStack {
                Image(systemName: "note.text")
            }
        }
        
        Settings {
            HStack {
                Spacer()
                Form {
                    KeyboardShortcuts.Recorder("Add new note", name: .createNote)
                    KeyboardShortcuts.Recorder(
                        "Paste note from clipboard", name: .createNoteFromClipboard)
                }
                Spacer()
            }
        }
    }
}
