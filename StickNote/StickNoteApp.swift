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
        MenuBarExtra("Sticknote", systemImage: "note.text") {
            MainMenu()
        }

        Settings {
            Form {
                KeyboardShortcuts.Recorder("Toggle Unicorn Mode:", name: .createNote)
            }
        }
    }
}
