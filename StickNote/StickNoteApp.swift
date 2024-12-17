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

        WindowGroup(id: "note-layout", for: Note.ID.self) { $id in

            if let id = id,
                let note =
                    (try? AppState.shared.context.fetch<Category>(
                        FetchDescriptor<Note>(predicate: #Predicate { $0.persistentModelID == id })))?
                    .first
            {
                NoteLayoutView(note: note)
            }

        }
        .windowResizability(.contentSize)
        .modelContext(AppState.shared.context)

        Settings {
            HStack {
                Spacer()
                Form {
                    KeyboardShortcuts.Recorder("Add new note", name: .createNote)
                    KeyboardShortcuts.Recorder(
                        "Paste note from clipboard", name: .createNoteFromClipboard)
                }
                
                Button("Reset all") {
                    try? AppState.shared.sharedModelContainer.erase()
                }
                Spacer()
            }
        }
    }
}
